import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import '../services/project_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import 'in_call_screen.dart';

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
          return const Scaffold(
            backgroundColor: AppTheme.ground,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (project == null) {
          return const Scaffold(
            backgroundColor: AppTheme.ground,
            body: Center(child: Text('Project not found')),
          );
        }

        final memberIds = <String>{project.createdBy, ...project.collaborators.keys}.toList();

        return Scaffold(
          backgroundColor: AppTheme.ground,
          appBar: SimpleAppBar(
            title: 'Call • ${project.title}',
            actions: [
              IconButton(
                icon: const Icon(Icons.event_available_outlined, size: 20, color: AppTheme.inkSecondary),
                onPressed: () => _showScheduleDialog(memberIds),
              ),
              IconButton(
                icon: const Icon(Icons.history_rounded, size: 20, color: AppTheme.inkSecondary),
                onPressed: _showHistory,
              ),
            ],
          ),
          body: StreamBuilder<ProjectCallSession?>(
            stream: ProjectService.instance.watchActiveProjectCall(widget.projectId),
            builder: (context, callSnapshot) {
              final activeCall = callSnapshot.data;

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                children: [
                  // Hero Call Room Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.panel,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.rule, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (activeCall != null && activeCall.active)
                                    ? const Color(0xFFDCFCE7)
                                    : AppTheme.groundMuted,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: (activeCall != null && activeCall.active)
                                      ? const Color(0xFF86EFAC)
                                      : AppTheme.rule,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: (activeCall != null && activeCall.active)
                                          ? const Color(0xFF16A34A)
                                          : AppTheme.inkSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    activeCall == null ? 'IDLE' : 'LIVE ${activeCall.type.toUpperCase()}',
                                    style: AppTheme.bodyFont(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: (activeCall != null && activeCall.active)
                                          ? const Color(0xFF15803D)
                                          : AppTheme.inkSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${project.collaboratorCount} collaborators',
                              style: AppTheme.bodyFont(fontSize: 12, color: AppTheme.inkSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          activeCall == null ? 'Project Call Room' : 'Active Conference Session',
                          style: AppTheme.displayFont(
                            color: AppTheme.ink,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Realtime WebRTC peer room with instant audio, video, and screen sharing across collaborators.',
                          style: AppTheme.bodyFont(
                            color: AppTheme.inkSecondary,
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (activeCall == null) ...[
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _startCall(type: 'team'),
                            icon: const Icon(Icons.groups_rounded, size: 18),
                            label: Text(
                              'Start Team Call',
                              style: AppTheme.bodyFont(fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _startSelectedCall(memberIds),
                            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18, color: AppTheme.ink),
                            label: Text(
                              'Select Members',
                              style: AppTheme.bodyFont(fontWeight: FontWeight.w600, color: AppTheme.ink),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppTheme.rule),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => _showScheduleDialog(memberIds),
                      icon: const Icon(Icons.event_available_outlined, size: 18, color: AppTheme.accent),
                      label: Text(
                        'Schedule Upcoming Call',
                        style: AppTheme.bodyFont(fontWeight: FontWeight.w600, color: AppTheme.accent),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.rule),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Team Members',
                      style: AppTheme.displayFont(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.inkSecondary,
                        letterSpacing: 0.2,
                      ),
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
                            final displayName = user?.name.trim().isNotEmpty == true
                                ? user!.name
                                : (user?.username.trim().isNotEmpty == true ? user!.username : 'Unknown');
                            final username = user?.username.trim().isNotEmpty == true ? user!.username : '';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.panel,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.rule, width: 1),
                              ),
                              child: Row(
                                children: [
                                  UserAvatar(
                                    name: displayName,
                                    username: username,
                                    size: 38,
                                    imageUrl: user?.photoUrl,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayName,
                                          style: AppTheme.bodyFont(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.ink),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '@${username.isNotEmpty ? username : '?'}',
                                          style: AppTheme.bodyFont(fontSize: 12, color: AppTheme.inkSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isAdmin ? AppTheme.accent.withOpacity(0.08) : AppTheme.groundMuted,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: isAdmin ? AppTheme.accent.withOpacity(0.2) : AppTheme.rule),
                                    ),
                                    child: Text(
                                      isAdmin ? 'ADMIN' : 'COLLABORATOR',
                                      style: AppTheme.bodyFont(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: isAdmin ? AppTheme.accent : AppTheme.inkSecondary,
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
                      onOpenRoom: () => _openCall(activeCall.id),
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
                    const SizedBox(height: 20),
                    Text(
                      'Connected Participants',
                      style: AppTheme.displayFont(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.inkSecondary,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FutureBuilder<Map<String, AppUser>>(
                      future: UserService.instance.getUsersByIds(activeCall.participants),
                      builder: (context, usersSnapshot) {
                        final users = usersSnapshot.data ?? {};
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
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
                  ],

                  const SizedBox(height: 24),
                  Text(
                    'Upcoming Calls',
                    style: AppTheme.displayFont(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.inkSecondary,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<List<ProjectCallSchedule>>(
                    stream: ProjectService.instance.watchProjectCallSchedules(widget.projectId),
                    builder: (context, scheduleSnapshot) {
                      final schedules = scheduleSnapshot.data ?? [];
                      final upcoming = schedules.where((schedule) => schedule.status == 'scheduled').toList();
                      if (upcoming.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.panel,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.rule, width: 1),
                          ),
                          child: Text(
                            'No upcoming calls scheduled yet. Tap "Schedule Upcoming Call" to create one.',
                            style: AppTheme.bodyFont(fontSize: 13, color: AppTheme.inkSecondary),
                          ),
                        );
                      }

                      return Column(
                        children: upcoming.map((schedule) {
                          return Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.panel,
                              border: Border.all(color: AppTheme.rule, width: 1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      schedule.title,
                                      style: AppTheme.bodyFont(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.ink),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accent.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${schedule.durationMinutes} min',
                                        style: AppTheme.bodyFont(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.accent),
                                      ),
                                    ),
                                  ],
                                ),
                                if (schedule.agenda.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    schedule.agenda,
                                    style: AppTheme.bodyFont(fontSize: 13, color: AppTheme.inkSecondary),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.schedule_rounded, size: 14, color: AppTheme.inkSecondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatDateTime(schedule.scheduledAt),
                                      style: AppTheme.bodyFont(fontSize: 12, color: AppTheme.inkSecondary),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
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
      final callId = await ProjectService.instance.startProjectCall(
        projectId: widget.projectId,
        type: type,
      );
      if (!mounted) return;
      await _openCall(callId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: AppTheme.field, behavior: SnackBarBehavior.floating),
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
              backgroundColor: AppTheme.panel,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.rule),
              ),
              title: Text('Select Participants', style: AppTheme.displayFont(fontSize: 18, fontWeight: FontWeight.w700)),
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
                          activeColor: AppTheme.accent,
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
                          title: Text(label, style: AppTheme.bodyFont(fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: Text('@${user?.username.isNotEmpty == true ? user!.username : 'user'}', style: AppTheme.bodyFont(fontSize: 12, color: AppTheme.inkSecondary)),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text('Cancel', style: AppTheme.bodyFont(color: AppTheme.inkSecondary)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, selected),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Start Call', style: AppTheme.bodyFont(fontWeight: FontWeight.w600, color: Colors.white)),
                ),
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
      final callId = await ProjectService.instance.startProjectCall(
        projectId: widget.projectId,
        type: 'selected',
        invitedParticipants: result.toList(),
      );
      if (!mounted) return;
      await _openCall(callId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: AppTheme.field, behavior: SnackBarBehavior.floating),
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
              backgroundColor: AppTheme.panel,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.rule),
              ),
              title: Text('Schedule Call', style: AppTheme.displayFont(fontSize: 18, fontWeight: FontWeight.w700)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      style: AppTheme.bodyFont(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Call title',
                        fillColor: AppTheme.groundMuted,
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: agendaController,
                      style: AppTheme.bodyFont(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Agenda / topic',
                        fillColor: AppTheme.groundMuted,
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descriptionController,
                      style: AppTheme.bodyFont(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Discussion description',
                        fillColor: AppTheme.groundMuted,
                        filled: true,
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: durationController,
                      keyboardType: TextInputType.number,
                      style: AppTheme.bodyFont(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Duration (minutes)',
                        fillColor: AppTheme.groundMuted,
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            scheduledAt == null
                                ? 'Choose date and time'
                                : _formatDateTime(scheduledAt!),
                            style: AppTheme.bodyFont(fontSize: 13, color: scheduledAt == null ? AppTheme.inkSecondary : AppTheme.ink),
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              firstDate: DateTime.now().subtract(const Duration(days: 1)),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                              initialDate: DateTime.now().add(const Duration(days: 1)),
                            );
                            if (date == null) return;
                            if (!context.mounted) return;
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                            );
                            if (time == null) return;
                            if (!context.mounted) return;
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
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.rule),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text('Pick Date/Time', style: AppTheme.bodyFont(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.accent)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppTheme.accent,
                      title: Text('Invite all collaborators', style: AppTheme.bodyFont(fontSize: 13, fontWeight: FontWeight.w600)),
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
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text('Cancel', style: AppTheme.bodyFont(color: AppTheme.inkSecondary)),
                ),
                ElevatedButton(
                  onPressed: scheduledAt == null ? null : () => Navigator.pop(dialogContext, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Schedule', style: AppTheme.bodyFont(fontWeight: FontWeight.w600, color: Colors.white)),
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
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: AppTheme.field, behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _openCall(String callId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InCallScreen(projectId: widget.projectId, callId: callId),
      ),
    );
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
      backgroundColor: AppTheme.panel,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                      icon: Icons.history_rounded,
                      title: 'No call history',
                      subtitle: 'Call sessions will appear here after they are started.',
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: sessions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.panel,
                        border: Border.all(color: AppTheme.rule, width: 1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: session.active ? const Color(0xFFDCFCE7) : AppTheme.groundMuted,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              session.active ? Icons.fiber_manual_record : Icons.history_rounded,
                              size: 16,
                              color: session.active ? const Color(0xFF15803D) : AppTheme.inkSecondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  session.type.toUpperCase(),
                                  style: AppTheme.bodyFont(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.ink),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Started by ${session.startedBy} · ${session.participants.length} participants',
                                  style: AppTheme.bodyFont(fontSize: 12, color: AppTheme.inkSecondary),
                                ),
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
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
              label: screenSharing ? 'Stop share' : 'Share',
              onPressed: onToggleScreenShare,
            ),
            _ControlButton(
              icon: Icons.meeting_room_outlined,
              label: 'Full Room',
              onPressed: onOpenRoom,
            ),
            if (isHost)
              _ControlButton(
                icon: Icons.call_end,
                label: 'End',
                destructive: true,
                onPressed: onEnd,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onJoin,
                icon: const Icon(Icons.videocam_rounded, size: 18),
                label: Text('Join Room', style: AppTheme.bodyFont(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onLeave,
                icon: const Icon(Icons.call_end, size: 18, color: AppTheme.danger),
                label: Text('Leave', style: AppTheme.bodyFont(fontWeight: FontWeight.w600, color: AppTheme.danger)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: Color(0xFFFECDD3)),
                  backgroundColor: const Color(0xFFFFF1F2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
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
      width: 130,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        border: Border.all(color: AppTheme.rule, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          UserAvatar(name: name, username: username, size: 40, imageUrl: imageUrl),
          const SizedBox(height: 8),
          Text(name, textAlign: TextAlign.center, style: AppTheme.bodyFont(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.ink)),
          const SizedBox(height: 2),
          Text('@$username', textAlign: TextAlign.center, style: AppTheme.bodyFont(fontSize: 11, color: AppTheme.inkSecondary)),
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
      icon: Icon(icon, size: 16),
      label: Text(label, style: AppTheme.bodyFont(fontSize: 12, fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        backgroundColor: destructive ? AppTheme.danger : AppTheme.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
