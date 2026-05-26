import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_service.dart';
import '../services/project_service.dart';
import '../screens/in_call_screen.dart';
import '../models/models.dart';

class CallsScreen extends StatefulWidget {
  final String projectId;

  const CallsScreen({super.key, required this.projectId});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> with SingleTickerProviderStateMixin {
  late final TabController _controller;

  final _titleCtrl = TextEditingController();
  final _whenCtrl = TextEditingController();
  final Map<String, bool> _selected = {};
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    _titleCtrl.dispose();
    _whenCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calls'),
        bottom: TabBar(
          controller: _controller,
          tabs: const [Tab(text: 'Schedule'), Tab(text: 'Start'), Tab(text: 'History')],
        ),
      ),
      body: TabBarView(
        controller: _controller,
        children: [
          _buildScheduleTab(),
          _buildStartTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildScheduleTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Call title')),
          const SizedBox(height: 12),
          TextField(controller: _whenCtrl, decoration: const InputDecoration(labelText: 'When (ISO datetime)')),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _scheduleCall,
            child: const Text('Schedule Call'),
          ),
        ],
      ),
    );
  }

  Widget _buildStartTab() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('projects').doc(widget.projectId).get(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final data = snap.data!.data() as Map<String, dynamic>? ?? {};
        final collaboratorsMap = (data['collaborators'] as Map<String, dynamic>?) ?? {};
        final collaboratorIds = collaboratorsMap.keys.where((id) => id != FirebaseFirestore.instance.app.name).toList();

        // Initialize selection map
        for (final id in collaboratorIds) {
          _selected.putIfAbsent(id, () => false);
        }

        return Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Invite collaborators'),
                  Row(children: [
                    const Text('Select all'),
                    Checkbox(
                      value: _selectAll,
                      onChanged: (v) {
                        setState(() {
                          _selectAll = v ?? false;
                          for (final k in _selected.keys) {
                            _selected[k] = _selectAll;
                          }
                        });
                      },
                    )
                  ])
                ],
              ),
              Expanded(
                child: collaboratorIds.isEmpty
                    ? const Center(child: Text('No collaborators to invite'))
                    : FutureBuilder<Map<String, dynamic>>(
                        future: UserService.instance.getUsersByIds(collaboratorIds).then((m) => m.map((k, v) => MapEntry(k, {'username': v.username, 'name': v.name}))),
                        builder: (context, usersSnap) {
                          final displayList = collaboratorIds.map((id) {
                            if (!usersSnap.hasData) return id;
                            final u = usersSnap.data![id];
                            if (u == null) return id;
                            return (u['name'] as String).isNotEmpty ? u['name'] as String : (u['username'] as String);
                          }).toList();

                          return ListView.builder(
                            itemCount: collaboratorIds.length,
                            itemBuilder: (context, idx) {
                              final id = collaboratorIds[idx];
                              final display = displayList[idx];
                              return CheckboxListTile(
                                value: _selected[id] ?? false,
                                onChanged: (v) => setState(() => _selected[id] = v ?? false),
                                title: Text(display),
                                subtitle: Text(id, style: const TextStyle(fontSize: 10)),
                              );
                            },
                          );
                        },
                      ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  await _startCallNow();
                },
                icon: const Icon(Icons.call),
                label: const Text('Start Call Now'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    return StreamBuilder<List<ProjectCallSession>>(
      stream: ProjectService.instance.watchProjectCallHistory(widget.projectId),
      builder: (context, snapshot) {
        final docs = snapshot.data ?? [];
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final d = docs[index];
            final startedById = d.startedBy;
            return FutureBuilder(
              future: UserService.instance.getUserById(startedById),
              builder: (context, userSnap) {
                final startedBy = userSnap.hasData
                    ? (userSnap.data!.name.isNotEmpty ? userSnap.data!.name : userSnap.data!.username)
                    : startedById;
                return ListTile(
                  title: Text(d.type.toUpperCase()),
                  subtitle: Text(startedBy),
                  trailing: Text(d.active ? 'Active' : 'Ended'),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _scheduleCall() async {
    final title = _titleCtrl.text.trim();
    final when = _whenCtrl.text.trim();
    final scheduledAt = DateTime.tryParse(when) ?? DateTime.now().add(const Duration(hours: 1));
    await ProjectService.instance.scheduleProjectCall(
      projectId: widget.projectId,
      title: title.isEmpty ? 'Meeting' : title,
      agenda: '',
      description: '',
      scheduledAt: scheduledAt,
      durationMinutes: 30,
      invitedParticipants: _selected.entries.where((entry) => entry.value).map((entry) => entry.key).toList(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Call scheduled')));
  }

  Future<void> _startCallNow() async {
    final selectedIds = _selected.entries.where((e) => e.value).map((e) => e.key).toList();

    final callId = await ProjectService.instance.startProjectCall(
      projectId: widget.projectId,
      type: 'instant',
      invitedParticipants: selectedIds,
    );
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InCallScreen(projectId: widget.projectId, callId: callId),
      ),
    );
  }
}
