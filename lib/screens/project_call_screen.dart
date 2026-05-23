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
  bool _speakerEnabled = true;
  bool _screenSharing = false;
  List<String> _selectedMembers = [];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return StreamBuilder<Project?>(
      stream: ProjectService.instance.watchProject(widget.projectId),
      builder: (context, projectSnapshot) {
        final project = projectSnapshot.data;
        
        if (projectSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        if (project == null) {
          return Scaffold(
            appBar: SimpleAppBar(title: 'Calls'),
            body: const Center(child: Text('Project not found')),
          );
        }

        final memberIds = <String>{
          project.createdBy,
          ...project.collaborators.keys
        }.toList();

        return Scaffold(
          appBar: SimpleAppBar(
            title: 'Calls • ${project.title}',
            actions: [
              IconButton(
                icon: const Icon(Icons.history),
                tooltip: 'Call history',
                onPressed: () => _showCallHistory(context, memberIds),
              ),
            ],
          ),
          body: StreamBuilder<ProjectCallSession?>(
            stream: ProjectService.instance.watchActiveProjectCall(widget.projectId),
            builder: (context, callSnapshot) {
              final activeCall = callSnapshot.data;

              // If there's an active call, show the active call UI
              if (activeCall != null) {
                return _buildActiveCallUI(
                  context,
                  activeCall,
                  memberIds,
                  isMobile,
                );
              }

              // Otherwise, show the pre-call dashboard
              return _buildPreCallUI(
                context,
                project,
                memberIds,
                isMobile,
              );
            },
          ),
        );
      },
    );
  }

  /// Pre-call UI: Dashboard with action cards
  Widget _buildPreCallUI(
    BuildContext context,
    Project project,
    List<String> memberIds,
    bool isMobile,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Call Management',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(height: 16),

          // Action Cards
          _CallActionCard(
            icon: Icons.flash_on_outlined,
            title: 'Start Instant Call',
            subtitle: 'Choose collaborators and start immediately.',
            onTap: () => _showStartInstantCallDialog(context, memberIds),
          ),
          const SizedBox(height: 12),

          _CallActionCard(
            icon: Icons.calendar_month_outlined,
            title: 'Schedule Call',
            subtitle: 'Set a time, agenda, and invite collaborators.',
            onTap: () => _showScheduleCallDialog(context, memberIds),
          ),
          const SizedBox(height: 12),

          _CallActionCard(
            icon: Icons.event_available_outlined,
            title: 'Upcoming Calls',
            subtitle: 'View scheduled calls for this project.',
            onTap: () => _showUpcomingCalls(context),
          ),
          const SizedBox(height: 12),

          _CallActionCard(
            icon: Icons.history_outlined,
            title: 'Call History',
            subtitle: 'Review past call sessions and participants.',
            onTap: () => _showCallHistory(context, memberIds),
          ),
        ],
      ),
    );
  }

  /// Active call UI: Controls and participant list
  Widget _buildActiveCallUI(
    BuildContext context,
    ProjectCallSession activeCall,
    List<String> memberIds,
    bool isMobile,
  ) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Call Status Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFDBEAFE),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.ring_volume_outlined,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Call Active',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${activeCall.participants.length} ${activeCall.participants.length == 1 ? 'participant' : 'participants'} joined',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Call Controls Grid
            GridView.count(
              crossAxisCount: isMobile ? 2 : 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                _CallControlButton(
                  icon: _audioEnabled
                      ? Icons.mic_outlined
                      : Icons.mic_off_outlined,
                  label: _audioEnabled ? 'Mute' : 'Unmute',
                  isActive: _audioEnabled,
                  onTap: () {
                    setState(() {
                      _audioEnabled = !_audioEnabled;
                    });
                  },
                ),
                _CallControlButton(
                  icon: _speakerEnabled
                      ? Icons.volume_up_outlined
                      : Icons.volume_off_outlined,
                  label: _speakerEnabled ? 'Speaker' : 'Muted',
                  isActive: _speakerEnabled,
                  onTap: () {
                    setState(() {
                      _speakerEnabled = !_speakerEnabled;
                    });
                  },
                ),
                _CallControlButton(
                  icon: _screenSharing
                      ? Icons.stop_screen_share_outlined
                      : Icons.screen_share_outlined,
                  label: _screenSharing ? 'Stop Share' : 'Share Screen',
                  isActive: _screenSharing,
                  onTap: () {
                    setState(() {
                      _screenSharing = !_screenSharing;
                    });
                  },
                ),
                _CallControlButton(
                  icon: Icons.call_end_outlined,
                  label: 'End Call',
                  isActive: false,
                  isDanger: true,
                  onTap: () => _endCall(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Participants List
            Text(
              'Participants (${activeCall.participants.length})',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            FutureBuilder<Map<String, AppUser>>(
              future: UserService.instance.getUsersByIds(activeCall.participants),
              builder: (context, usersSnapshot) {
                final users = usersSnapshot.data ?? {};

                if (activeCall.participants.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          'No participants yet',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                }

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: activeCall.participants.map((userId) {
                        final user = users[userId];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: AppTheme.primary,
                                child: Text(
                                  (user?.username ?? 'U').characters.first
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                user?.username ?? 'Unknown',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showStartInstantCallDialog(
    BuildContext context,
    List<String> memberIds,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        scrollable: true,
        title: const Text('Start Instant Call'),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: MediaQuery.of(dialogContext).size.height * 0.55,
          ),
          child: const Text(
            'Select collaborators to invite to this call.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement call start logic
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Call feature coming soon'),
                ),
              );
            },
            child: const Text('Start Call'),
          ),
        ],
      ),
    );
  }

  void _showScheduleCallDialog(
    BuildContext context,
    List<String> memberIds,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        scrollable: true,
        title: const Text('Schedule Call'),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: MediaQuery.of(dialogContext).size.height * 0.68,
          ),
          child: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Title'),
                TextField(
                  decoration: InputDecoration(hintText: 'Call title'),
                ),
                SizedBox(height: 12),
                Text('Agenda'),
                TextField(
                  decoration: InputDecoration(hintText: 'What will you discuss?'),
                  maxLines: 3,
                ),
                SizedBox(height: 12),
                Text('Date & Time'),
                TextField(
                  decoration: InputDecoration(hintText: 'Select date and time'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Call scheduled (feature coming soon)'),
                ),
              );
            },
            child: const Text('Schedule'),
          ),
        ],
      ),
    );
  }

  void _showUpcomingCalls(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upcoming Calls'),
        content: const Text('No upcoming calls scheduled.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showCallHistory(BuildContext context, List<String> memberIds) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Call History'),
        content: const Text('No previous calls found.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _endCall(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Call'),
        content: const Text('Are you sure you want to end this call?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
            ),
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement call end logic
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Call ended'),
                ),
              );
            },
            child: const Text('End Call'),
          ),
        ],
      ),
    );
  }
}

class _ProjectCallScreenState extends State<ProjectCallScreen> {
  bool _audioEnabled = true;
  bool _speakerEnabled = true;
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
              Widget _buildPreCallUI(BuildContext context, Project project, List<String> memberIds, bool isMobile) {

                  padding: const EdgeInsets.all(16),
                // ACTIVE CALL: Show call controls only
                return _buildActiveCallUI(context, activeCall, memberIds, isMobile);
              } else {
                      _DashboardActionCard(
                        icon: Icons.flash_on_outlined,
                        title: 'Start Instant Call',
                        subtitle: 'Choose collaborators and start immediately.',
                        onTap: () => _startSelectedCall(memberIds),
                      ),
                      const SizedBox(height: 12),
                      _DashboardActionCard(
                        icon: Icons.calendar_month_outlined,
                        title: 'Schedule Call',
                        subtitle: 'Set a time, agenda, and invite collaborators.',
                        onTap: () => _showScheduleDialog(memberIds),
                      ),
                      const SizedBox(height: 12),
                      _DashboardActionCard(
                        icon: Icons.event_available_outlined,
                        title: 'Upcoming Calls',
                        subtitle: 'View scheduled calls for this project.',
                        onTap: _showUpcomingCalls,
                      ),
                      const SizedBox(height: 12),
                      _DashboardActionCard(
                        icon: Icons.history_outlined,
                        title: 'Previous Calls',
                        subtitle: 'Review past call sessions and participants.',
                        onTap: _showHistory,
                      ),
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Call Status
                return SafeArea(
                  child: ListView(
                    padding: EdgeInsets.all(isMobile ? 16 : 20),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 18,
                              backgroundColor: Color(0xFFDBEAFE),
                              child: Icon(Icons.ring_volume_outlined, color: AppTheme.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Call Active', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 2),
                                  Text('${activeCall.participants.length} joined', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: _showHistory,
                              child: const Text('History'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      FutureBuilder<Map<String, AppUser>>(
                        future: UserService.instance.getUsersByIds(activeCall.participants),
                        builder: (context, usersSnapshot) {
                          final users = usersSnapshot.data ?? {};
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Joined collaborators', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 12),
                                  if (activeCall.participants.isEmpty)
                                    const Text('Waiting for participants to join.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary))
                                  else
                                    Wrap(
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
                                          label: Text(user?.name.split(' ').first ?? user?.username ?? 'User', maxLines: 1),
                                        );
                                      }).toList(),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: isMobile ? 2 : 4,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.1,
                        children: [
                          _CallControlTile(
                            active: _audioEnabled,
                            icon: _audioEnabled ? Icons.mic : Icons.mic_off,
                            label: _audioEnabled ? 'Mute' : 'Unmute',
                            onTap: () async {
                              setState(() => _audioEnabled = !_audioEnabled);
                              await ProjectService.instance.updateCallState(
                                projectId: widget.projectId,
                                callId: activeCall.id,
                                audioEnabled: _audioEnabled,
                              );
                            },
                          ),
                          _CallControlTile(
                            active: _speakerEnabled,
                            icon: Icons.volume_up_outlined,
                            label: _speakerEnabled ? 'Speaker On' : 'Speaker Off',
                            onTap: () => setState(() => _speakerEnabled = !_speakerEnabled),
                          ),
                          _CallControlTile(
                            active: _screenSharing,
                            icon: Icons.screen_share_outlined,
                            label: _screenSharing ? 'Sharing' : 'Share Screen',
                            onTap: () => setState(() => _screenSharing = !_screenSharing),
                          ),
                          _CallControlTile(
                            active: false,
                            destructive: true,
                            icon: Icons.call_end,
                            label: 'Leave Call',
                            onTap: () => ProjectService.instance.leaveProjectCall(projectId: widget.projectId, callId: activeCall.id),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
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
    final titleController = TextEditingController(text: 'Instant Call');
    final agendaController = TextEditingController();
    final selected = <String>{};
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Start Instant Call'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
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
                        decoration: const InputDecoration(labelText: 'Optional agenda'),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 14),
                      FutureBuilder<Map<String, AppUser>>(
                        future: UserService.instance.getUsersByIds(memberIds),
                        builder: (context, usersSnapshot) {
                          final users = usersSnapshot.data ?? {};
                          return Column(
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
                                title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Text('@${user?.username.isNotEmpty == true ? user!.username : '?'}'),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
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
        type: 'instant',
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
                      controller: durationController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Duration (minutes)'),
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

  Future<void> _showUpcomingCalls() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: StreamBuilder<List<ProjectCallSchedule>>(
              stream: ProjectService.instance.watchProjectCallSchedules(widget.projectId),
              builder: (context, snapshot) {
                final schedules = (snapshot.data ?? []).where((schedule) => schedule.status == 'scheduled').toList();
                if (schedules.isEmpty) {
                  return const Center(
                    child: EmptyState(
                      icon: Icons.event_outlined,
                      title: 'No upcoming calls',
                      subtitle: 'Scheduled calls will appear here.',
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: schedules.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final schedule = schedules[index];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(schedule.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Text(_formatDateTime(schedule.scheduledAt), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                            if (schedule.agenda.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(schedule.agenda, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                            ],
                          ],
                        ),
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

class _DashboardActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DashboardActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppTheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.35)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}


/// Call Action Card for pre-call dashboard
class _CallActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CallActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_outlined,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Call Control Button for active call controls
class _CallControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool isDanger;
  final VoidCallback onTap;

  const _CallControlButton({
    required this.icon,
    required this.label,
    required this.isActive,
    this.isDanger = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isDanger
        ? AppTheme.danger
        : isActive
            ? AppTheme.primary
            : Colors.grey[200];
    final foregroundColor =
        isDanger || isActive ? Colors.white : Colors.grey[700];

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: foregroundColor,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
