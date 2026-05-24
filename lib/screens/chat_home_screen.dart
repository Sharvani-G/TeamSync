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

        final isMobile = MediaQuery.of(context).size.width < 600;
        return Scaffold(
          appBar: SimpleAppBar(title: project.title),
          body: isMobile
              ? Column(
                  children: [
                    // Compact channel row for mobile
                    Container(
                      height: 64,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(bottom: BorderSide(color: AppTheme.border)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: StreamBuilder<List<ProjectChannel>>(
                              stream: ProjectService.instance.watchProjectChannels(widget.projectId),
                              builder: (context, snapshot) {
                                final channels = snapshot.data ?? [];
                                if (channels.isEmpty) return const SizedBox.shrink();
                                return ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: channels.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                                  itemBuilder: (ctx, i) {
                                    final ch = channels[i];
                                    final active = ch.id == _selectedChannelId;
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() => _selectedChannelId = ch.id);
                                        ProjectService.instance.markChannelRead(projectId: widget.projectId, channelId: ch.id);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: active ? AppTheme.primary : Colors.grey[100],
                                          borderRadius: BorderRadius.circular(28),
                                          border: Border.all(color: active ? AppTheme.primary : AppTheme.border),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.tag, size: 16, color: Colors.white),
                                            const SizedBox(width: 8),
                                            Text('# ${ch.name}', style: TextStyle(color: active ? Colors.white : AppTheme.textPrimary, fontWeight: active ? FontWeight.w800 : FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          IconButton(
                            tooltip: 'Create channel',
                            onPressed: _showCreateChannelDialog,
                            icon: Icon(Icons.add_circle_outline, color: AppTheme.primary),
                          ),
                        ],
                      ),
                    ),
                    // Expanded chat view
                    Expanded(child: ChatChannelView(projectId: widget.projectId, channelId: _selectedChannelId)),
                  ],
                )
              : Row(
                  children: [
                    // LEFT SIDEBAR
                    Container(
                      width: 280,
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
                          Expanded(
                            child: StreamBuilder<List<ProjectChannel>>(
                              stream: ProjectService.instance.watchProjectChannels(widget.projectId),
                              builder: (context, snapshot) {
                                final channels = snapshot.data ?? [];

                                if (channels.isEmpty) {
                                  return const Center(child: Text('No channels'));
                                }

                                return ListView.builder(
                                  itemCount: channels.length,
                                  itemBuilder: (context, index) {
                                    final ch = channels[index];
                                    final isActive = ch.id == _selectedChannelId;

                                    return ListTile(
                                      dense: true,
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
                                      subtitle: ch.lastMessageAt != null ? Text(_formatLastActivity(ch.lastMessageAt!), style: const TextStyle(fontSize: 11)) : null,
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
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),

                    // RIGHT PANEL: Active channel messages
                    Expanded(
                      child: ChatChannelView(projectId: widget.projectId, channelId: _selectedChannelId),
                    ),
                  ],
                ),
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
