import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../services/browser_timezone.dart';
import '../services/project_service.dart';
import '../services/user_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';

class CallsScreen extends StatefulWidget {
  final String projectId;

  const CallsScreen({super.key, required this.projectId});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> with WidgetsBindingObserver {
  final GlobalKey<FormState> _scheduleFormKey = GlobalKey<FormState>();
  final TextEditingController _meetingTitleController = TextEditingController();
  final TextEditingController _meetingAgendaController = TextEditingController();
  final TextEditingController _customDurationController = TextEditingController();

  final Map<String, bool> _collaboratorSelections = <String, bool>{};

  DateTime? _scheduledAt;
  String _durationSelection = '30';
  bool _isScheduling = false;
  bool _isStartingCall = false;
  int _historyVisibleCount = 10;

  late final Stream<Project?> _projectStream;
  late final Stream<List<ProjectCallSchedule>> _schedulesStream;
  late final Stream<List<ProjectCallSession>> _historyStream;

  Timer? _joinTimer;
  Timer? _backgroundTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _projectStream = ProjectService.instance.watchProject(widget.projectId);
    _schedulesStream = ProjectService.instance.watchProjectCallSchedules(widget.projectId);
    _historyStream = ProjectService.instance.watchProjectCallHistory(widget.projectId);

    _joinTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _joinTimer?.cancel();
    _backgroundTimer?.cancel();
    _meetingTitleController.dispose();
    _meetingAgendaController.dispose();
    _customDurationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (state == AppLifecycleState.paused) {
      _backgroundTimer = Timer(const Duration(hours: 1), () async {
        final sessions = await FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId)
            .collection('callSessions')
            .where('status', isEqualTo: 'active')
            .where('callerUid', isEqualTo: uid)
            .get();
        for (final doc in sessions.docs) {
          await doc.reference.update({'status': 'ended'});
        }
      });
    } else if (state == AppLifecycleState.resumed) {
      _backgroundTimer?.cancel();
    }
  }

  List<String> _participantIds(Project project) {
    final ids = <String>{project.createdBy, ...project.collaborators.keys};
    return ids.where((id) => id.trim().isNotEmpty).toList();
  }

  String _timezoneLabel() {
    return DateTime.now().timeZoneName;
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final initial = _scheduledAt ?? now.add(const Duration(minutes: 10));

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.accent,
              onPrimary: Colors.white,
              surface: AppTheme.panel,
              onSurface: AppTheme.ink,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.accent,
              onPrimary: Colors.white,
              surface: AppTheme.panel,
              onSurface: AppTheme.ink,
            ),
          ),
          child: child!,
        );
      },
    );

    if (time == null || !mounted) return;

    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    if (selected.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a future time.')),
      );
      return;
    }

    setState(() => _scheduledAt = selected);
  }

  int _resolveDurationMinutes() {
    if (_durationSelection == 'custom') {
      return int.tryParse(_customDurationController.text.trim()) ?? 30;
    }
    return int.tryParse(_durationSelection) ?? 30;
  }

  Future<void> _scheduleMeeting(Project project, List<String> allParticipantIds) async {
    if (!_scheduleFormKey.currentState!.validate()) return;

    if (_scheduledAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a date and time.')),
      );
      return;
    }

    final selectedParticipants = allParticipantIds
        .where((id) => _collaboratorSelections[id] ?? true)
        .toList();

    if (selectedParticipants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one participant.')),
      );
      return;
    }

    setState(() => _isScheduling = true);

    try {
      final duration = _resolveDurationMinutes();
      final scheduleId = await ProjectService.instance.scheduleProjectCall(
        projectId: widget.projectId,
        title: _meetingTitleController.text.trim(),
        agenda: _meetingAgendaController.text.trim(),
        description: _meetingAgendaController.text.trim(),
        scheduledAt: _scheduledAt!,
        durationMinutes: duration,
        invitedParticipants: selectedParticipants,
      );

      _resetScheduleForm();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meeting scheduled successfully!'),
            backgroundColor: AppColors.dpSuccess,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to schedule: $e'), backgroundColor: AppColors.dpDanger),
        );
      }
    } finally {
      if (mounted) setState(() => _isScheduling = false);
    }
  }

  Future<void> _startInstantMeet() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() => _isStartingCall = true);

    try {
      final project = await ProjectService.instance.watchProject(widget.projectId).first;
      if (project == null) return;

      final meetLink = 'https://meet.jit.si/teamsync-${widget.projectId}';

      final callRef = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('callSessions')
          .add({
        'sessionId': widget.projectId,
        'meetLink': meetLink,
        'callerUid': currentUser.uid,
        'callerName': currentUser.displayName ?? currentUser.email ?? 'Someone',
        'status': 'active',
        'startedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 1))),
        'projectId': widget.projectId,
      });

      final teamMembers = _participantIds(project);
      final myUid = currentUser.uid;

      for (final uid in teamMembers) {
        if (uid == myUid || uid.isEmpty) continue;
        await NotificationService.instance.createNotification(
          userId: uid,
          type: 'call_started',
          title: 'Live Meet Started',
          body: '${currentUser.displayName ?? "Someone"} started a live Jitsi Meet call.',
          projectId: widget.projectId,
          data: {
            'projectId': widget.projectId,
            'callerName': currentUser.displayName ?? currentUser.email ?? 'Someone',
          },
        );
      }

      final uri = Uri.parse(meetLink);
      final canLaunch = await canLaunchUrl(uri);
      if (canLaunch) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open meeting link')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.dpDanger),
        );
      }
    } finally {
      if (mounted) setState(() => _isStartingCall = false);
    }
  }

  void _resetScheduleForm() {
    _meetingTitleController.clear();
    _meetingAgendaController.clear();
    _customDurationController.clear();
    setState(() {
      _scheduledAt = null;
      _durationSelection = '30';
    });
  }

  Widget _buildNoLiveCalls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.groundMuted,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.rule),
      ),
      child: Row(
        children: [
          const Icon(Icons.phone_disabled_outlined, color: AppTheme.inkSecondary, size: 20),
          const SizedBox(width: 12),
          Text(
            'No live calls in session',
            style: AppTheme.bodySmall.copyWith(color: AppTheme.inkSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildInstantCallSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('projects')
              .doc(widget.projectId)
              .collection('callSessions')
              .orderBy('startedAt', descending: true)
              .limit(1)
              .snapshots(),
          builder: (context, snapshot) {
            final currentUser = FirebaseAuth.instance.currentUser;

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox.shrink();
            }

            if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildNoLiveCalls();
            }

            final doc = snapshot.data!.docs.first;
            final session = doc.data() as Map<String, dynamic>;
            final status = session['status'] as String? ?? '';

            if (status != 'active') {
              return _buildNoLiveCalls();
            }

            final meetLink = session['meetLink'] as String? ?? '';
            final callerName = session['callerName'] as String? ?? 'Someone';
            final callerUid = session['callerUid'] as String? ?? '';
            final expiresAt = session['expiresAt'] as Timestamp?;
            final isMe = currentUser?.uid == callerUid;

            if (expiresAt != null && DateTime.now().isAfter(expiresAt.toDate())) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                doc.reference.update({'status': 'ended'});
              });
              return _buildNoLiveCalls();
            }

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.dpSuccessBg,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppColors.dpSuccess.withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.phone_in_talk, color: AppColors.dpSuccess, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isMe ? 'Your meeting is live' : '$callerName started a call',
                      style: AppTheme.heading3.copyWith(fontSize: 14, color: AppColors.dpSuccess),
                    ),
                  ),
                  if (isMe) ...[
                    TextButton(
                      onPressed: () => doc.reference.update({'status': 'ended'}),
                      child: const Text('End', style: TextStyle(color: AppColors.dpDanger)),
                    ),
                    const SizedBox(width: 8),
                  ],
                  ElevatedButton(
                    onPressed: meetLink.isEmpty
                        ? null
                        : () => launchUrl(Uri.parse(meetLink), mode: LaunchMode.externalApplication),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.dpSuccess,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    child: const Text('Join Now', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ground,
      appBar: const SimpleAppBar(title: 'Calls & Meetings'),
      body: SafeArea(
        child: StreamBuilder<Project?>(
          stream: _projectStream,
          builder: (context, projectSnapshot) {
            final project = projectSnapshot.data;
            if (projectSnapshot.connectionState == ConnectionState.waiting && project == null) {
              return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
            }
            if (project == null) {
              return const EmptyState(
                icon: Icons.error_outline,
                title: 'Project Not Found',
                subtitle: 'This project could not be located.',
              );
            }

            final participantIds = _participantIds(project);

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Section 1: Instant Call
                      _SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.dpInfoBg,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.videocam_outlined, color: AppTheme.accent, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Instant Meeting', style: AppTheme.heading2),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Start an on-demand video room with your collaborators',
                                        style: AppTheme.metadataText,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              height: 46,
                              child: ElevatedButton.icon(
                                onPressed: _isStartingCall ? null : _startInstantMeet,
                                icon: _isStartingCall
                                    ? const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.video_call, size: 20),
                                label: const Text('Start Instant Meet'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                  ),
                                ),
                              ),
                            ),
                            _buildInstantCallSection(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Section 2: Schedule Meeting
                      _SectionCard(
                        child: Form(
                          key: _scheduleFormKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: AppColors.dpInfoBg,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.calendar_month_outlined, color: AppTheme.accent, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Schedule Meeting', style: AppTheme.heading2),
                                        const SizedBox(height: 2),
                                        Text('Coordinate upcoming sessions with calendar invitations', style: AppTheme.metadataText),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _meetingTitleController,
                                style: AppTheme.bodySmall.copyWith(color: AppTheme.ink),
                                decoration: _inputDecoration('Meeting Title (e.g. Sprint Sync, Architecture Review)'),
                                validator: (value) =>
                                    (value ?? '').trim().isEmpty ? 'Meeting title is required' : null,
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'Select Collaborators',
                                style: AppTheme.labelText.copyWith(fontWeight: FontWeight.w700, color: AppTheme.ink),
                              ),
                              const SizedBox(height: 8),
                              _CollaboratorRoster(
                                participantIds: participantIds,
                                selected: _collaboratorSelections,
                                height: 180,
                                onSelectionChanged: (id, val) =>
                                    setState(() => _collaboratorSelections[id] = val),
                              ),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: _durationSelection,
                                      dropdownColor: AppTheme.panel,
                                      decoration: _inputDecoration('Duration'),
                                      iconEnabledColor: AppTheme.ink,
                                      style: AppTheme.bodySmall.copyWith(color: AppTheme.ink),
                                      items: const [
                                        DropdownMenuItem(value: '15', child: Text('15 minutes')),
                                        DropdownMenuItem(value: '30', child: Text('30 minutes')),
                                        DropdownMenuItem(value: '45', child: Text('45 minutes')),
                                        DropdownMenuItem(value: '60', child: Text('1 hour')),
                                        DropdownMenuItem(value: '90', child: Text('1.5 hours')),
                                        DropdownMenuItem(value: '120', child: Text('2 hours')),
                                        DropdownMenuItem(value: 'custom', child: Text('Custom')),
                                      ],
                                      onChanged: (value) {
                                        if (value == null) return;
                                        setState(() => _durationSelection = value);
                                      },
                                    ),
                                  ),
                                  if (_durationSelection == 'custom') ...[
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _customDurationController,
                                        keyboardType: TextInputType.number,
                                        style: AppTheme.bodySmall.copyWith(color: AppTheme.ink),
                                        decoration: _inputDecoration('Minutes'),
                                        validator: (value) {
                                          final parsed = int.tryParse((value ?? '').trim());
                                          if (parsed == null || parsed <= 0) {
                                            return 'Enter valid minutes';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 18),
                              InkWell(
                                onTap: _pickDateTime,
                                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                child: InputDecorator(
                                  decoration: _inputDecoration('Scheduled Date & Time'),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.schedule_outlined, color: AppTheme.accent, size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _scheduledAt == null
                                              ? 'Pick date and time'
                                              : DateFormat('EEE, MMM d, yyyy • h:mm a').format(_scheduledAt!.toLocal()),
                                          style: AppTheme.bodySmall.copyWith(
                                            color: _scheduledAt == null ? AppTheme.textMuted : AppTheme.ink,
                                          ),
                                        ),
                                      ),
                                      Text(_timezoneLabel(), style: AppTheme.metadataText),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              TextFormField(
                                controller: _meetingAgendaController,
                                style: AppTheme.bodySmall.copyWith(color: AppTheme.ink),
                                maxLines: 3,
                                decoration: _inputDecoration('Meeting Agenda (optional items, objectives, topics)'),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _isScheduling ? null : _resetScheduleForm,
                                      child: const Text('Reset'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _isScheduling
                                          ? null
                                          : () => _scheduleMeeting(project, participantIds),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.accent,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: _isScheduling
                                          ? const SizedBox(
                                              height: 18,
                                              width: 18,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                            )
                                          : const Text('Schedule Meeting', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Section 3: Upcoming Meetings
                      _SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Upcoming Meetings', style: AppTheme.heading2),
                            const SizedBox(height: 14),
                            StreamBuilder<List<ProjectCallSchedule>>(
                              stream: _schedulesStream,
                              builder: (context, snapshot) {
                                final schedules = snapshot.data ?? const <ProjectCallSchedule>[];
                                final upcoming = schedules.where((s) => s.status == 'scheduled').toList();

                                if (snapshot.connectionState == ConnectionState.waiting && upcoming.isEmpty) {
                                  return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                                }

                                if (upcoming.isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: Text(
                                      'No upcoming meetings scheduled for this project.',
                                      style: AppTheme.bodySmall.copyWith(color: AppTheme.inkSecondary),
                                    ),
                                  );
                                }

                                return ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: upcoming.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final s = upcoming[index];
                                    final now = DateTime.now();
                                    final scheduledAt = s.scheduledAt;
                                    final durationMin = s.durationMinutes;
                                    final meetLink = s.meetLink;

                                    final joinableFrom = scheduledAt.subtract(const Duration(minutes: 5));
                                    final joinableUntil = scheduledAt.add(Duration(minutes: durationMin * 2));

                                    final bool canJoin = now.isAfter(joinableFrom) && now.isBefore(joinableUntil);
                                    final bool isExpired = now.isAfter(joinableUntil);

                                    Widget actionWidget;
                                    if (isExpired) {
                                      actionWidget = Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppTheme.groundMuted,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text('Ended', style: AppTheme.metadataText),
                                      );
                                    } else if (canJoin && meetLink.isNotEmpty) {
                                      actionWidget = ElevatedButton.icon(
                                        onPressed: () async {
                                          final uri = Uri.parse(meetLink);
                                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                                        },
                                        icon: const Icon(Icons.videocam, size: 16, color: Colors.white),
                                        label: const Text('Join Room', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.dpSuccess,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                      );
                                    } else {
                                      final timeLeft = joinableFrom.difference(now);
                                      final minutesLeft = timeLeft.inMinutes + 1;
                                      actionWidget = Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppTheme.groundMuted,
                                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                          border: Border.all(color: AppTheme.rule),
                                        ),
                                        child: Text(
                                          'Opens in ${minutesLeft}m',
                                          style: AppTheme.labelText.copyWith(color: AppTheme.inkSecondary),
                                        ),
                                      );
                                    }

                                    return Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: AppTheme.groundMuted,
                                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                        border: Border.all(color: AppTheme.rule),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(s.title, style: AppTheme.heading3.copyWith(fontSize: 14.5)),
                                                const SizedBox(height: 3),
                                                Text(
                                                  DateFormat('EEE, MMM d • h:mm a').format(s.scheduledAt),
                                                  style: AppTheme.metadataText,
                                                ),
                                              ],
                                            ),
                                          ),
                                          actionWidget,
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Section 4: Call History
                      _SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('Call History', style: AppTheme.heading2),
                                const Spacer(),
                                Text('Completed sessions', style: AppTheme.metadataText),
                              ],
                            ),
                            const SizedBox(height: 14),
                            StreamBuilder<List<ProjectCallSession>>(
                              stream: _historyStream,
                              builder: (context, snapshot) {
                                final history = snapshot.data ?? const <ProjectCallSession>[];
                                final visibleHistory = history.take(_historyVisibleCount).toList();

                                if (snapshot.connectionState == ConnectionState.waiting && history.isEmpty) {
                                  return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                                }

                                if (visibleHistory.isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    child: Text(
                                      'No completed sessions logged for this project yet.',
                                      style: AppTheme.bodySmall.copyWith(color: AppTheme.inkSecondary),
                                    ),
                                  );
                                }

                                return Column(
                                  children: [
                                    ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: visibleHistory.length,
                                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                                      itemBuilder: (context, index) {
                                        final session = visibleHistory[index];
                                        return _HistoryTile(session: session);
                                      },
                                    ),
                                    if (history.length > visibleHistory.length)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: TextButton(
                                            onPressed: () => setState(() => _historyVisibleCount += 10),
                                            child: const Text('Load More History'),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: AppTheme.bodySmall.copyWith(color: AppTheme.inkSecondary),
      filled: true,
      fillColor: AppTheme.panel,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: child,
    );
  }
}

class _CollaboratorRoster extends StatelessWidget {
  final List<String> participantIds;
  final Map<String, bool> selected;
  final double height;
  final void Function(String userId, bool value)? onSelectionChanged;

  const _CollaboratorRoster({
    required this.participantIds,
    required this.selected,
    required this.height,
    this.onSelectionChanged,
  });

  bool _isSelected(String userId) => selected[userId] ?? true;

  @override
  Widget build(BuildContext context) {
    if (participantIds.isEmpty) {
      return Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.groundMuted,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.rule),
        ),
        child: Text(
          'No verified collaborators found.',
          style: AppTheme.bodySmall.copyWith(color: AppTheme.inkSecondary),
        ),
      );
    }

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.rule),
      ),
      child: FutureBuilder<Map<String, AppUser>>(
        future: UserService.instance.getUsersByIds(participantIds),
        builder: (context, snapshot) {
          final profiles = snapshot.data ?? <String, AppUser>{};
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: participantIds.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.rule),
            itemBuilder: (context, index) {
              final userId = participantIds[index];
              final profile = profiles[userId];
              final displayName = profile == null
                  ? userId
                  : (profile.name.trim().isNotEmpty
                      ? profile.name.trim()
                      : profile.username.trim().isNotEmpty
                          ? profile.username.trim()
                          : userId);

              return CheckboxListTile(
                dense: true,
                value: _isSelected(userId),
                activeColor: AppTheme.accent,
                checkColor: Colors.white,
                onChanged: (value) {
                  final newVal = value ?? false;
                  if (onSelectionChanged != null) {
                    onSelectionChanged!(userId, newVal);
                  }
                },
                title: Text(
                  displayName,
                  style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w600, color: AppTheme.ink),
                ),
                subtitle: profile?.username != null && profile!.username.isNotEmpty
                    ? Text('@${profile.username}', style: AppTheme.metadataText)
                    : null,
                controlAffinity: ListTileControlAffinity.leading,
              );
            },
          );
        },
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final ProjectCallSession session;

  const _HistoryTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final agenda = session.agenda.trim().isEmpty ? 'No agenda specified.' : session.agenda.trim();
    final dateText = DateFormat('EEE, MMM d • h:mm a').format(session.startedAt.toLocal());
    final durationLabel = session.durationMinutes > 0 ? '${session.durationMinutes}m' : '0m';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.groundMuted,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  session.meetingTitle.trim().isEmpty ? 'Scheduled Session' : session.meetingTitle.trim(),
                  style: AppTheme.heading3.copyWith(fontSize: 14.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.dpInfoBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
                ),
                child: Text(
                  durationLabel,
                  style: AppTheme.labelText.copyWith(color: AppTheme.accent, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            agenda,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.bodySmall.copyWith(color: AppTheme.inkSecondary, height: 1.35),
          ),
          const SizedBox(height: 8),
          Text(dateText, style: AppTheme.metadataText.copyWith(fontSize: 11.5)),
        ],
      ),
    );
  }
}
