import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import '../services/project_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import 'chat_channel_screen.dart';

class ChatHomeScreen extends StatefulWidget {
  final String projectId;
  const ChatHomeScreen({super.key, required this.projectId});

  @override
  State<ChatHomeScreen> createState() => _ChatHomeScreenState();
}

class _ChatHomeScreenState extends State<ChatHomeScreen> {
  String _selectedChannelId = 'general';
  
  // Breakpoint: 600dp is standard for tablet
  static const double _mobileBreakpoint = 600;

  @override
  void initState() {
    super.initState();
    // Try to restore last active channel for the user
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      ProjectService.instance.getUserActiveChannel(projectId: widget.projectId, userId: user.uid).then((value) {
        if (value != null && value.isNotEmpty) {
          setState(() => _selectedChannelId = value);
        }
      }).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < _mobileBreakpoint;

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

        if (isMobile) {
          // MOBILE: Show channel list only
          return Scaffold(
            appBar: SimpleAppBar(title: project.title),
            body: _buildChannelList(),
            floatingActionButton: FloatingActionButton(
              onPressed: _showCreateChannelDialog,
              tooltip: 'Create channel',
              child: const Icon(Icons.add),
            ),
          );
        } else {
          // DESKTOP: Show split view
          return Scaffold(
            appBar: SimpleAppBar(title: project.title),
            body: Row(
              children: [
                // LEFT SIDEBAR
                SizedBox(
                  width: 280,
                  child: Container(
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: AppTheme.border)),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              const Expanded(child: Text('Channels', style: TextStyle(fontWeight: FontWeight.w700))),
                              IconButton(
                                tooltip: 'Create channel',
                                onPressed: _showCreateChannelDialog,
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                            ],
                          ),
                        ),
                        Expanded(child: _buildChannelList()),
                      ],
                    ),
                  ),
                ),
                // RIGHT PANEL: Active channel messages
                Expanded(
                  child: ChatChannelView(projectId: widget.projectId, channelId: _selectedChannelId),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildChannelList() {
    return StreamBuilder<List<ProjectChannel>>(
      stream: ProjectService.instance.watchProjectChannels(widget.projectId),
      builder: (context, snapshot) {
        final channels = snapshot.data ?? [];

        if (channels.isEmpty) {
          return const Center(child: Text('No channels'));
        }

        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < _mobileBreakpoint;

        return ListView.builder(
          itemCount: channels.length,
          itemBuilder: (context, index) {
            final ch = channels[index];
            final isActive = ch.id == _selectedChannelId;

            if (isMobile) {
              // MOBILE: Full-screen navigation on tap
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Card(
                  elevation: 0,
                  color: isActive ? AppTheme.primary.withOpacity(0.1) : null,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    leading: const Icon(Icons.tag),
                    title: Text('# ${ch.name}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: FutureBuilder<int>(
                      future: _getUnread(ch.id),
                      builder: (context, unreadSnap) {
                        final unread = unreadSnap.data ?? 0;
                        if (unread <= 0) return const SizedBox(width: 40);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.danger,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        );
                      },
                    ),
                    onTap: () {
                      setState(() => _selectedChannelId = ch.id);
                      ProjectService.instance.markChannelRead(projectId: widget.projectId, channelId: ch.id);
                      ProjectService.instance.setUserActiveChannel(projectId: widget.projectId, channelId: ch.id);
                      // Navigate to full-screen chat
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            appBar: SimpleAppBar(
                              title: '# ${ch.name}',
                              showBack: true,
                            ),
                            body: ChatChannelView(projectId: widget.projectId, channelId: ch.id),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            } else {
              // DESKTOP: List view with menu
              return ListTile(
                dense: false,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: const Icon(Icons.tag),
                title: Row(
                  children: [
                    Expanded(child: Text('# ${ch.name}', style: TextStyle(fontWeight: isActive ? FontWeight.w800 : FontWeight.w600))),
                    FutureBuilder<int>(
                      future: _getUnread(ch.id),
                      builder: (context, unreadSnap) {
                        final unread = unreadSnap.data ?? 0;
                        if (unread <= 0) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(unread > 99 ? '99+' : '$unread', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                        );
                      },
                    ),
                  ],
                ),
                selected: isActive,
                onTap: () {
                  setState(() => _selectedChannelId = ch.id);
                  ProjectService.instance.markChannelRead(projectId: widget.projectId, channelId: ch.id);
                  ProjectService.instance.setUserActiveChannel(projectId: widget.projectId, channelId: ch.id);
                },
                trailing: PopupMenuButton<String>(
                  onSelected: (value) => _handleChannelAction(value, ch),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'rename', child: Text('Rename')),
                    if (ch.id != 'general') const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    const PopupMenuItem(value: 'leave', child: Text('Leave')),
                  ],
                ),
              );
            }
          },
        );
      },
    );
  }

  Future<int> _getUnread(String channelId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;
    return await ProjectService.instance.getChannelUnreadCount(projectId: widget.projectId, channelId: channelId, userId: user.uid);
  }

  String _formatLastActivity(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _showCreateChannelDialog() async {
    final nameController = TextEditingController();
    bool isPrivate = false;
    final membersController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Create Channel'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Channel name')),
              Row(
                children: [
                  const Text('Private'),
                  const Spacer(),
                  StatefulBuilder(builder: (sctx, setStateSB) {
                    return Switch(value: isPrivate, onChanged: (v) => setStateSB(() => isPrivate = v));
                  }),
                ],
              ),
              if (isPrivate) TextField(controller: membersController, decoration: const InputDecoration(labelText: 'Invite usernames (comma separated)')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final invited = membersController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
                try {
                  final id = await ProjectService.instance.createChannel(projectId: widget.projectId, name: name, isPrivate: isPrivate, invitedMembers: invited);
                  setState(() => _selectedChannelId = id);
                  await ProjectService.instance.setUserActiveChannel(projectId: widget.projectId, channelId: id);
                  Navigator.pop(ctx, true);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      // Mark as read after creation
      ProjectService.instance.markChannelRead(projectId: widget.projectId, channelId: _selectedChannelId);
    }
  }

  Future<void> _handleChannelAction(String action, ProjectChannel ch) async {
    try {
      if (action == 'rename') {
        final controller = TextEditingController(text: ch.name);
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: const Text('Rename Channel'),
              content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Channel name')),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Rename'))],
            );
          },
        );
        if (ok == true) {
          await ProjectService.instance.renameChannel(projectId: widget.projectId, channelId: ch.id, newName: controller.text);
        }
      } else if (action == 'delete') {
        final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Delete Channel'), content: const Text('Delete this channel? This cannot be undone.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))]));
        if (confirm == true) {
          await ProjectService.instance.deleteChannel(projectId: widget.projectId, channelId: ch.id);
          if (_selectedChannelId == ch.id) {
            setState(() => _selectedChannelId = 'general');
            await ProjectService.instance.setUserActiveChannel(projectId: widget.projectId, channelId: 'general');
          }
        }
      } else if (action == 'leave') {
        final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Leave Channel'), content: const Text('Leave this channel? You will lose access.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave'))]));
        if (confirm == true) {
          await ProjectService.instance.leaveChannel(projectId: widget.projectId, channelId: ch.id);
          if (_selectedChannelId == ch.id) {
            setState(() => _selectedChannelId = 'general');
            await ProjectService.instance.setUserActiveChannel(projectId: widget.projectId, channelId: 'general');
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action failed: ${e.toString()}')));
    }
  }
}
