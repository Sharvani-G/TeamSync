import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import '../services/project_service.dart';
import '../services/user_service.dart';
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
                                              Text(ch.name.startsWith('#') ? ch.name.substring(1) : ch.name, style: TextStyle(color: active ? Colors.white : AppTheme.textPrimary, fontWeight: active ? FontWeight.w800 : FontWeight.w600)),
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
                                    final displayName = ch.name.startsWith('#') ? ch.name.substring(1) : ch.name;

                                    return ListTile(
                                      dense: true,
                                      leading: const Icon(Icons.tag),
                                      title: Row(
                                        children: [
                                          Expanded(child: Text(displayName, style: TextStyle(fontWeight: isActive ? FontWeight.w800 : FontWeight.w600))),
                                          FutureBuilder<int>(
                                            future: _getUnread(ch.id),
                                            builder: (context, unreadSnap) {
                                              final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                                              var unread = unreadSnap.data ?? 0;
                                              if (ch.lastMessageSenderId == currentUserId) {
                                                unread = 0;
                                              }
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
    // No private toggle in redesigned flow; channels are created with selected members
    // Prefetch collaborators for the project so we can show a selectable list
    final currentUser = FirebaseAuth.instance.currentUser;
    Map<String, AppUser> usersById = {};
    try {
      final project = await ProjectService.instance.watchProject(widget.projectId).first;
      if (project != null) {
        final ids = project.collaborators.keys.toList();
        if (!ids.contains(project.createdBy)) ids.add(project.createdBy);
        // Exclude current user from invite list
        if (currentUser != null) ids.remove(currentUser.uid);
        usersById = await UserService.instance.getUsersByIds(ids);
      }
    } catch (_) {
      usersById = {};
    }

    final selected = <String, bool>{};
    final usersList = usersById.values.toList();
    usersList.sort((a, b) => a.username.compareTo(b.username));
    for (final u in usersList) selected[u.id] = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (sctx, setStateSB) {
          return AlertDialog(
            title: const Text('Create Channel'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Channel Name')),
                Row(
                  children: [
                    const Text('Invite members'),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setStateSB(() {
                        final all = selected.keys.toList();
                        for (final k in all) selected[k] = true;
                      }),
                      child: const Text('Add All'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 220,
                  width: double.maxFinite,
                  child: usersList.isEmpty
                      ? const Center(child: Text('No collaborators to invite'))
                      : ListView.builder(
                          itemCount: usersList.length,
                          itemBuilder: (ctx2, i) {
                            final u = usersList[i];
                            return CheckboxListTile(
                              value: selected[u.id] ?? false,
                              title: Text('@${u.username}'),
                              subtitle: Text(u.name),
                              onChanged: (v) => setStateSB(() => selected[u.id] = v ?? false),
                            );
                          },
                        ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Channel name cannot be empty')));
                    return;
                  }

                  final invitedUserIds = selected.entries.where((e) => e.value).map((e) => e.key).toList();
                  try {
                    final id = await ProjectService.instance.createChannel(projectId: widget.projectId, name: name, invitedMembers: invitedUserIds);
                    setState(() => _selectedChannelId = id);
                    await ProjectService.instance.setUserActiveChannel(projectId: widget.projectId, channelId: id);
                    Navigator.pop(ctx, true);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
                  }
                },
                child: const Text('Create Channel'),
              ),
            ],
          );
        });
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
