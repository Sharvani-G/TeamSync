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


class CallsScreen extends StatefulWidget {
  final String projectId;

  const CallsScreen({super.key, required this.projectId});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> with WidgetsBindingObserver {
  final GlobalKey<FormState> _scheduleFormKey = GlobalKey<FormState>();
  final TextEditingController _meetingTitleController = TextEditingController();
  final TextEditingController _meetingAgendaController =
      TextEditingController();
  final TextEditingController _customDurationController =
      TextEditingController();

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
      _backgroundTimer = Timer(
        const Duration(hours: 1), () async {
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

  bool _isSelected(String userId) {
    return _collaboratorSelections[userId] ?? true;
  }

  Set<String> _selectedParticipantIds(Iterable<String> participantIds) {
    return participantIds.where(_isSelected).toSet();
  }

  int _resolvedDurationMinutes() {
    if (_durationSelection != 'custom') {
      return int.tryParse(_durationSelection) ?? 30;
    }

    return int.tryParse(_customDurationController.text.trim()) ?? 0;
  }

  String _timezoneLabel() {
    return detectBrowserTimeZone();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final initialDate = _scheduledAt ?? now.add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (time == null || !mounted) return;

    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    if (picked.isBefore(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose a future date and time.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _scheduledAt = picked);
  }

  Future<void> _scheduleMeeting(
      Project project, List<String> participantIds) async {
    if (!_scheduleFormKey.currentState!.validate()) {
      return;
    }

    final scheduledAt = _scheduledAt;
    if (scheduledAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose a future date and time.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final selectedIds = _selectedParticipantIds(participantIds);
    if (selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one collaborator.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final durationMinutes = _resolvedDurationMinutes();
    if (durationMinutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid custom duration.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isScheduling = true);
    try {
      await ProjectService.instance.scheduleProjectCall(
        projectId: widget.projectId,
        title: _meetingTitleController.text.trim(),
        agenda: _meetingAgendaController.text.trim(),
        description: _meetingAgendaController.text.trim(),
        scheduledAt: scheduledAt,
        durationMinutes: durationMinutes,
        invitedParticipants: selectedIds.toList(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Meeting scheduled successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _resetScheduleForm();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isScheduling = false);
      }
    }
  }

  Future<void> _startInstantMeet() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Show loading indicator using existing pattern
    setState(() => _isStartingCall = true);

    try {
      // 1. Create Firestore document reference first
      //    This gives us the doc ID before writing
      final sessionRef = FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId)
        .collection('callSessions')
        .doc();

      // 2. Generate Jitsi link from doc ID
      //    ONLY done here, NEVER at display time
      final docId = sessionRef.id;
      final safeId = docId
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .substring(0, 12);
      final meetLink = 
        'https://meet.jit.si/TeamSync$safeId';

      // 3. Write to Firestore BEFORE opening link
      //    This is what makes other collaborators 
      //    see the Join button
      await sessionRef.set({
        'sessionId': docId,
        'meetLink': meetLink,
        'callerUid': currentUser.uid,
        'callerName': currentUser.displayName
          ?? currentUser.email
          ?? 'Someone',
        'status': 'active',
        'startedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(
            const Duration(hours: 1))),
        'projectId': widget.projectId,
      });

      // 4. VERIFY write succeeded — log it
      print('callSession written: ${sessionRef.path}');
      print('meetLink stored: $meetLink');

      // 5. Send notification to all collaborators
      //    Use existing NotificationService
      //    type: 'call_started'
      //    payload: { 
      //      'projectId': widget.projectId,
      //      'callerName': currentUser.displayName
      //    }
      //    Do NOT pass meetLink in notification —
      //    collaborators read it from Firestore
      final projectDoc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .get();
      if (projectDoc.exists) {
        final projectData = projectDoc.data() ?? {};
        final collaborators = Map<String, dynamic>.from(projectData['collaborators'] ?? {});
        final creatorId = projectData['createdBy'] as String? ?? '';
        final teamMembers = <String>{creatorId, ...collaborators.keys};
        
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
      }

      // 6. Open Jitsi for the caller
      //    Use externalApplication — opens browser
      //    not the Jitsi app
      final uri = Uri.parse(meetLink);
      final canLaunch = await canLaunchUrl(uri);
      if (canLaunch) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open meeting')));
      }
    } catch (e) {
      print('Error starting meet: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() => _isStartingCall = false);
      }
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Row(children: [
        Icon(Icons.phone_disabled, color: Colors.grey.shade600, size: 20),
        const SizedBox(width: 12),
        Text('No live calls right now',
          style: TextStyle(color: Colors.grey.shade500)),
      ]),
    );
  }

  Widget _buildInstantCallSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Keep existing Start Meet button exactly here
        // Do not move or change it
        
        const SizedBox(height: 12),
        
        // Live call status — reads from Firestore
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId)
            .collection('callSessions')
            .orderBy('startedAt', descending: true)
            .limit(1)
            .snapshots(),
          builder: (context, snapshot) {
            final currentUser =
              FirebaseAuth.instance.currentUser;

            // Still loading
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const SizedBox.shrink();
            }

            // Firestore error — log it
            if (snapshot.hasError) {
              print('callSessions error: '
                '${snapshot.error}');
              return Text('Error: ${snapshot.error}',
                style: const TextStyle(
                  color: Colors.red));
            }

            // No active call
            if (!snapshot.hasData ||
                snapshot.data!.docs.isEmpty) {
              return _buildNoLiveCalls();
            }

            // Active call exists
            final doc = snapshot.data!.docs.first;
            final session =
              doc.data() as Map<String, dynamic>;
            final status = session['status'] as String? ?? '';

            if (status != 'active') {
              return _buildNoLiveCalls();
            }

            final meetLink =
              session['meetLink'] as String? ?? '';
            final callerName =
              session['callerName'] 
                as String? ?? 'Someone';
            final callerUid =
              session['callerUid'] as String? ?? '';
            final expiresAt =
              session['expiresAt'] as Timestamp?;
            final isMe =
              currentUser?.uid == callerUid;

            // Check expiry
            if (expiresAt != null &&
                DateTime.now().isAfter(
                  expiresAt.toDate())) {
              // Auto end expired session
              WidgetsBinding.instance
                .addPostFrameCallback((_) {
                doc.reference.update(
                  {'status': 'ended'});
              });
              return _buildNoLiveCalls();
            }

            // Show active call banner
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade900
                  .withValues(alpha: 0.3),
                borderRadius:
                  BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.green.shade700),
              ),
              child: Row(children: [
                Icon(Icons.phone_in_talk,
                  color: Colors.green.shade400,
                  size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isMe
                      ? 'Your call is live'
                      : '$callerName started a call',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500),
                  ),
                ),
                if (isMe) ...[
                  TextButton(
                    onPressed: () =>
                      doc.reference.update(
                        {'status': 'ended'}),
                    child: const Text('End',
                      style: TextStyle(
                        color: Colors.red)),
                  ),
                  const SizedBox(width: 8),
                ],
                ElevatedButton(
                  onPressed: meetLink.isEmpty
                    ? null
                    : () => launchUrl(
                        Uri.parse(meetLink),
                        mode: LaunchMode
                          .externalApplication),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green),
                  child: const Text('Join',
                    style: TextStyle(
                      color: Colors.white)),
                ),
              ]),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1520),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1723),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Calls'),
      ),
      body: SafeArea(
        child: StreamBuilder<Project?>(
          stream: _projectStream,
          builder: (context, projectSnapshot) {
            final project = projectSnapshot.data;
            if (projectSnapshot.connectionState == ConnectionState.waiting &&
                project == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (project == null) {
              return const Center(
                child: Text(
                  'Project not found',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }

            final participantIds = _participantIds(project);
            return LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SectionCard(
                          child: Form(
                            key: _scheduleFormKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_month_outlined,
                                        color: Colors.white),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Schedule meeting',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                TextFormField(
                                  controller: _meetingTitleController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: _inputDecoration('Meeting title'),
                                  validator: (value) {
                                    if ((value ?? '').trim().isEmpty) {
                                      return 'Meeting title is required';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Verified collaborators',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 10),
                                _CollaboratorRoster(
                                  participantIds: participantIds,
                                  selected: _collaboratorSelections,
                                  height: 180,
                                  onSelectionChanged: (id, val) => setState(() => _collaboratorSelections[id] = val),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        value: _durationSelection,
                                        dropdownColor: const Color(0xFF172534),
                                        decoration:
                                            _inputDecoration('Duration'),
                                        iconEnabledColor: Colors.white,
                                        style: const TextStyle(
                                            color: Colors.white),
                                        items: const [
                                          DropdownMenuItem(
                                              value: '15', child: Text('15m')),
                                          DropdownMenuItem(
                                              value: '30', child: Text('30m')),
                                          DropdownMenuItem(
                                              value: '45', child: Text('45m')),
                                          DropdownMenuItem(
                                              value: '60', child: Text('1h')),
                                          DropdownMenuItem(
                                              value: '90', child: Text('1.5h')),
                                          DropdownMenuItem(
                                              value: '120', child: Text('2h')),
                                          DropdownMenuItem(
                                              value: 'custom',
                                              child: Text('Custom')),
                                        ],
                                        onChanged: (value) {
                                          if (value == null) return;
                                          setState(
                                              () => _durationSelection = value);
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _customDurationController,
                                        enabled: _durationSelection == 'custom',
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(
                                            color: Colors.white),
                                        decoration:
                                            _inputDecoration('Custom minutes'),
                                        validator: (value) {
                                          if (_durationSelection != 'custom') {
                                            return null;
                                          }
                                          final parsed = int.tryParse(
                                              (value ?? '').trim());
                                          if (parsed == null || parsed <= 0) {
                                            return 'Enter minutes';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                InkWell(
                                  onTap: _pickDateTime,
                                  borderRadius: BorderRadius.circular(12),
                                  child: InputDecorator(
                                    decoration: _inputDecoration('Date & time'),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.schedule_outlined,
                                            color: Colors.white70),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            _scheduledAt == null
                                                ? 'Pick a future local time'
                                                : DateFormat(
                                                        'EEE, MMM d • h:mm a')
                                                    .format(_scheduledAt!
                                                        .toLocal()),
                                            style: TextStyle(
                                              color: _scheduledAt == null
                                                  ? Colors.white54
                                                  : Colors.white,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          _timezoneLabel(),
                                          style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _meetingAgendaController,
                                  style: const TextStyle(color: Colors.white),
                                  maxLines: 4,
                                  decoration:
                                      _inputDecoration('Meeting Agenda'),
                                ),
                                const SizedBox(height: 18),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: _isScheduling
                                            ? null
                                            : () {
                                                if (Navigator.of(context)
                                                    .canPop()) {
                                                  Navigator.of(context).pop();
                                                } else {
                                                  _resetScheduleForm();
                                                }
                                              },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          side: const BorderSide(
                                              color: Colors.white24),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: const Text('Cancel'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: _isScheduling
                                            ? null
                                            : () => _scheduleMeeting(
                                                project, participantIds),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF5CA8FF),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: _isScheduling
                                            ? const SizedBox(
                                                height: 18,
                                                width: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2),
                                              )
                                            : const Text('Schedule meeting'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _SectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.phone_android_outlined,
                                      color: Colors.white),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Start a Meet',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.podcasts_outlined,
                                      color: Colors.white54),
                                ],
                              ),
                              const SizedBox(height: 20),
                              _CollaboratorRoster(
                                participantIds: participantIds,
                                selected: _collaboratorSelections,
                                height: 160,
                                dense: true,
                                onSelectionChanged: (id, val) => setState(() => _collaboratorSelections[id] = val),
                              ),
                              const SizedBox(height: 18),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _isStartingCall
                                      ? null
                                      : () =>
                                          _startInstantMeet(),
                                  icon: _isStartingCall
                                      ? const SizedBox(
                                          height: 16,
                                          width: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Icon(Icons.video_call_outlined),
                                  label: const Text('Start Meet'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1DDA8A),
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 15),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildInstantCallSection(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _SectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Upcoming meetings',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 14),
                              StreamBuilder<List<ProjectCallSchedule>>(
                                stream: _schedulesStream,
                                builder: (context, snapshot) {
                                  final schedules = snapshot.data ??
                                      const <ProjectCallSchedule>[];
                                  final upcoming = schedules
                                      .where((s) => s.status == 'scheduled')
                                      .toList();

                                  if (snapshot.connectionState ==
                                          ConnectionState.waiting &&
                                      upcoming.isEmpty) {
                                    return const Center(child: CircularProgressIndicator());
                                  }

                                  if (upcoming.isEmpty) {
                                    return const Text(
                                      'No upcoming meetings.',
                                      style: TextStyle(color: Colors.white54),
                                    );
                                  }

                                  return ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: upcoming.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 12),
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

                                      Widget joinButton;
                                      if (isExpired) {
                                        joinButton = Text(
                                          'Meeting ended',
                                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                        );
                                      } else if (canJoin && meetLink.isNotEmpty) {
                                        joinButton = ElevatedButton.icon(
                                          onPressed: () async {
                                            final uri = Uri.parse(meetLink);
                                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                                          },
                                          icon: const Icon(Icons.video_call, size: 18, color: Colors.white),
                                          label: const Text('Join Meet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                        );
                                      } else if (canJoin && meetLink.isEmpty) {
                                        joinButton = Text(
                                          'Link unavailable',
                                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                        );
                                      } else {
                                        final timeLeft = joinableFrom.difference(now);
                                        final minutesLeft = timeLeft.inMinutes + 1;
                                        joinButton = ElevatedButton(
                                          onPressed: null,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.grey.shade800,
                                            disabledBackgroundColor: Colors.grey.shade800,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                          child: Text(
                                            'Opens in ${minutesLeft}m',
                                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                          ),
                                        );
                                      }

                                      return Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0E1A27),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(s.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                  Text(DateFormat.yMMMd().add_jm().format(s.scheduledAt), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                                  if (isExpired) ...[
                                                    const SizedBox(height: 4),
                                                    Text('${s.joinedUids.length} joined', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            joinButton,
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
                        const SizedBox(height: 18),
                        _SectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Call history',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Completed scheduled rooms',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Colors.white54,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              StreamBuilder<List<ProjectCallSession>>(
                                stream: _historyStream,
                                builder: (context, snapshot) {
                                  final history = snapshot.data ??
                                      const <ProjectCallSession>[];
                                  final visibleHistory = history
                                      .take(_historyVisibleCount)
                                      .toList();

                                  if (snapshot.connectionState ==
                                          ConnectionState.waiting &&
                                      history.isEmpty) {
                                    return const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 24),
                                      child: Center(
                                          child: CircularProgressIndicator()),
                                    );
                                  }

                                  if (visibleHistory.isEmpty) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 18),
                                      child: Text(
                                        'No completed scheduled rooms yet.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Colors.white54,
                                            ),
                                      ),
                                    );
                                  }

                                  return Column(
                                    children: [
                                      ListView.separated(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount: visibleHistory.length,
                                        separatorBuilder: (_, __) =>
                                            const SizedBox(height: 12),
                                        itemBuilder: (context, index) {
                                          final session = visibleHistory[index];
                                          return _HistoryTile(session: session);
                                        },
                                      ),
                                      if (history.length >
                                          visibleHistory.length)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 10),
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: TextButton(
                                              onPressed: () {
                                                setState(() {
                                                  _historyVisibleCount += 10;
                                                });
                                              },
                                              child: const Text('Load more'),
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
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF5CA8FF), width: 1.5),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white24),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF122131),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }
}

class _CollaboratorRoster extends StatelessWidget {
  final List<String> participantIds;
  final Map<String, bool> selected;
  final double height;
  final bool dense;

  const _CollaboratorRoster({
    required this.participantIds,
    required this.selected,
    required this.height,
    this.dense = false,
    this.onSelectionChanged,
  });

  bool _isSelected(String userId) => selected[userId] ?? true;

  // Callback to notify parent state to update selection map via setState.
  final void Function(String userId, bool value)? onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    if (participantIds.isEmpty) {
      return Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF0E1A27),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: const Text(
          'No verified collaborators found.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A27),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Scrollbar(
        child: FutureBuilder<Map<String, AppUser>>(
          future: UserService.instance.getUsersByIds(participantIds),
          builder: (context, snapshot) {
            final profiles = snapshot.data ?? <String, AppUser>{};
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: participantIds.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Colors.white10),
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
                  dense: dense,
                  value: _isSelected(userId),
                  activeColor: const Color(0xFF5CA8FF),
                  checkColor: Colors.white,
                  onChanged: (value) {
                    final newVal = value ?? false;
                    if (onSelectionChanged != null) {
                      onSelectionChanged!(userId, newVal);
                    }
                  },
                  title: Text(
                    displayName,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    userId,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final ProjectCallSession session;

  const _HistoryTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final agenda = session.agenda.trim().isEmpty
        ? 'No agenda saved.'
        : session.agenda.trim();
    final dateText =
        DateFormat('EEE, MMM d • h:mm a').format(session.startedAt.toLocal());
    final durationLabel =
        session.durationMinutes > 0 ? '${session.durationMinutes}m' : '0m';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A27),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 92, top: 2, bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.meetingTitle.trim().isEmpty
                      ? 'Scheduled meeting'
                      : session.meetingTitle.trim(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  agenda,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, height: 1.35),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: _Chip(text: durationLabel),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Text(
              dateText,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;

  const _Chip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF243449),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}
